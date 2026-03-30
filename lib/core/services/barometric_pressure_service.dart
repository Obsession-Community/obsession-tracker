import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Barometric pressure service for altitude accuracy and weather awareness
/// Provides pressure readings, altitude calculations, and weather trend analysis
class BarometricPressureService {
  BarometricPressureService();

  StreamSubscription<BarometerEvent>? _barometerSubscription;
  StreamController<PressureReading>? _readingController;
  StreamController<AltitudeEvent>? _altitudeController;
  StreamController<WeatherTrend>? _weatherController;

  // Filtering and calibration
  static const double _alpha = 0.9; // Low-pass filter coefficient for pressure
  double _filteredPressure = 0.0;
  double _referencePressure = 1013.25; // Sea level pressure in hPa
  double _referenceAltitude = 0.0; // Reference altitude in meters
  bool _isCalibrated = false;

  // Pressure history for trend analysis
  final List<PressureDataPoint> _pressureHistory = <PressureDataPoint>[];
  static const int _maxHistorySize = 360; // 3 hours at 30-second intervals
  Timer? _historyTimer;

  // Weather trend analysis
  WeatherTrendType _currentTrend = WeatherTrendType.stable;
  double _trendStrength = 0.0;

  // Altitude calculation
  double _currentAltitude = 0.0;
  double _altitudeAccuracy = 0.0;

  /// Stream of pressure readings
  Stream<PressureReading> get readingStream {
    _readingController ??= StreamController<PressureReading>.broadcast();
    return _readingController!.stream;
  }

  /// Stream of altitude events
  Stream<AltitudeEvent> get altitudeStream {
    _altitudeController ??= StreamController<AltitudeEvent>.broadcast();
    return _altitudeController!.stream;
  }

  /// Stream of weather trend updates
  Stream<WeatherTrend> get weatherStream {
    _weatherController ??= StreamController<WeatherTrend>.broadcast();
    return _weatherController!.stream;
  }

  /// Current filtered pressure in hPa
  double get currentPressure => _filteredPressure;

  /// Current calculated altitude in meters
  double get currentAltitude => _currentAltitude;

  /// Current weather trend
  WeatherTrendType get currentTrend => _currentTrend;

  /// Trend strength (0.0 to 1.0)
  double get trendStrength => _trendStrength;

  /// Whether the barometer is calibrated
  bool get isCalibrated => _isCalibrated;

  /// Reference pressure for altitude calculations
  double get referencePressure => _referencePressure;

  /// Reference altitude for calibration
  double get referenceAltitude => _referenceAltitude;

  /// Start barometric pressure service
  Future<void> start() async {
    try {
      await stop(); // Ensure clean start

      _readingController ??= StreamController<PressureReading>.broadcast();
      _altitudeController ??= StreamController<AltitudeEvent>.broadcast();
      _weatherController ??= StreamController<WeatherTrend>.broadcast();

      debugPrint('🌡️ Starting barometric pressure service...');

      // Start barometer stream
      _barometerSubscription = barometerEventStream().listen(
        _handleBarometerEvent,
        onError: _handleBarometerError,
        onDone: () {
          debugPrint('🌡️ Barometer stream completed');
        },
      );

      // Start periodic history recording and trend analysis
      _historyTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _recordHistoryAndAnalyzeTrend(),
      );

      debugPrint('🌡️ Barometric pressure service started');
    } catch (e) {
      debugPrint('🌡️ Error starting barometric pressure service: $e');
      rethrow;
    }
  }

  /// Stop barometric pressure service
  Future<void> stop() async {
    await _barometerSubscription?.cancel();
    _barometerSubscription = null;

    _historyTimer?.cancel();
    _historyTimer = null;

    await _readingController?.close();
    _readingController = null;

    await _altitudeController?.close();
    _altitudeController = null;

    await _weatherController?.close();
    _weatherController = null;

    debugPrint('🌡️ Barometric pressure service stopped');
  }

  /// Calibrate barometer with known altitude
  void calibrateWithAltitude(double knownAltitude) {
    if (_filteredPressure > 0) {
      _referenceAltitude = knownAltitude;
      _referencePressure =
          _calculateSeaLevelPressure(_filteredPressure, knownAltitude);
      _isCalibrated = true;

      debugPrint('🌡️ Barometer calibrated:');
      debugPrint('  Known altitude: ${knownAltitude.toStringAsFixed(1)}m');
      debugPrint(
          '  Current pressure: ${_filteredPressure.toStringAsFixed(2)} hPa');
      debugPrint(
          '  Calculated sea level pressure: ${_referencePressure.toStringAsFixed(2)} hPa');
    }
  }

  /// Calibrate barometer with known sea level pressure
  void calibrateWithSeaLevelPressure(double seaLevelPressure) {
    _referencePressure = seaLevelPressure;
    _referenceAltitude = 0.0;
    _isCalibrated = true;

    debugPrint(
        '🌡️ Barometer calibrated with sea level pressure: ${seaLevelPressure.toStringAsFixed(2)} hPa');
  }

  /// Reset calibration to standard atmosphere
  void resetCalibration() {
    _referencePressure = 1013.25; // Standard atmosphere
    _referenceAltitude = 0.0;
    _isCalibrated = false;

    debugPrint('🌡️ Barometer calibration reset to standard atmosphere');
  }

  void _handleBarometerEvent(BarometerEvent event) {
    try {
      debugPrint('Raw barometer reading: ${event.pressure} hPa');

      // Apply low-pass filter to pressure data
      if (_filteredPressure == 0.0) {
        // Initialize filter
        _filteredPressure = event.pressure;
      } else {
        // Apply filter
        _filteredPressure =
            _alpha * _filteredPressure + (1 - _alpha) * event.pressure;
      }

      // Calculate altitude
      _currentAltitude = _calculateAltitude(_filteredPressure);
      _altitudeAccuracy = _calculateAltitudeAccuracy();

      // Create pressure reading
      final reading = PressureReading(
        rawPressure: event.pressure,
        filteredPressure: _filteredPressure,
        altitude: _currentAltitude,
        altitudeAccuracy: _altitudeAccuracy,
        timestamp: DateTime.now(),
        isCalibrated: _isCalibrated,
        referencePressure: _referencePressure,
        weatherTrend: _currentTrend,
        trendStrength: _trendStrength,
      );

      _readingController?.add(reading);

      // Emit altitude event if significant change
      _checkAltitudeChange();
    } catch (e) {
      debugPrint('🌡️ Error processing barometer event: $e');
    }
  }

  void _handleBarometerError(Object error) {
    debugPrint('🌡️ Barometer error: $error');
  }

  double _calculateAltitude(double pressure) {
    // Barometric formula: h = (T0/L) * ((P0/P)^(R*L/g*M) - 1)
    // Simplified version: h = 44330 * (1 - (P/P0)^(1/5.255))
    if (pressure <= 0) return 0.0;

    final double ratio = pressure / _referencePressure;
    final double altitude = 44330.0 * (1.0 - math.pow(ratio, 1.0 / 5.255));

    return altitude + _referenceAltitude;
  }

  double _calculateSeaLevelPressure(double pressure, double altitude) {
    // Reverse barometric formula to find sea level pressure
    final double adjustedAltitude = altitude - _referenceAltitude;
    final double ratio = 1.0 - (adjustedAltitude / 44330.0);
    return pressure / math.pow(ratio, 5.255);
  }

  double _calculateAltitudeAccuracy() {
    // Estimate altitude accuracy based on calibration and pressure stability
    if (!_isCalibrated) return 50.0; // Poor accuracy without calibration

    // Better accuracy with recent calibration and stable pressure
    double accuracy = 10.0; // Base accuracy in meters

    // Reduce accuracy if pressure is changing rapidly (weather effects)
    if (_trendStrength > 0.5) {
      accuracy += _trendStrength * 20.0;
    }

    return accuracy;
  }

  void _checkAltitudeChange() {
    // Emit altitude event for significant changes (>2m)
    double lastEmittedAltitude = 0.0;

    if ((lastEmittedAltitude - _currentAltitude).abs() > 2.0) {
      final altitudeEvent = AltitudeEvent(
        altitude: _currentAltitude,
        change: _currentAltitude - lastEmittedAltitude,
        accuracy: _altitudeAccuracy,
        timestamp: DateTime.now(),
        isCalibrated: _isCalibrated,
      );

      _altitudeController?.add(altitudeEvent);
      lastEmittedAltitude = _currentAltitude;

      debugPrint(
          '🌡️ Altitude change: ${_currentAltitude.toStringAsFixed(1)}m (±${_altitudeAccuracy.toStringAsFixed(1)}m)');
    }
  }

  void _recordHistoryAndAnalyzeTrend() {
    if (_filteredPressure <= 0) return;

    // Add current pressure to history
    final dataPoint = PressureDataPoint(
      pressure: _filteredPressure,
      timestamp: DateTime.now(),
    );

    _pressureHistory.add(dataPoint);

    // Remove old data points
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 3));
    _pressureHistory
        .removeWhere((point) => point.timestamp.isBefore(cutoffTime));

    // Enforce maximum history size
    while (_pressureHistory.length > _maxHistorySize) {
      _pressureHistory.removeAt(0);
    }

    // Analyze trend if we have enough data
    if (_pressureHistory.length >= 6) {
      // At least 3 minutes of data
      _analyzePressureTrend();
    }
  }

  void _analyzePressureTrend() {
    if (_pressureHistory.length < 6) return;

    // Calculate trend over different time periods
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final threeHoursAgo = now.subtract(const Duration(hours: 3));

    // Get pressure readings from different time periods
    final currentPressure = _pressureHistory.last.pressure;

    double? oneHourPressure;
    double? threeHourPressure;

    for (final point in _pressureHistory.reversed) {
      if (oneHourPressure == null && point.timestamp.isBefore(oneHourAgo)) {
        oneHourPressure = point.pressure;
      }
      if (threeHourPressure == null &&
          point.timestamp.isBefore(threeHoursAgo)) {
        threeHourPressure = point.pressure;
        break;
      }
    }

    // Calculate trends
    double oneHourChange = 0.0;
    double threeHourChange = 0.0;

    if (oneHourPressure != null) {
      oneHourChange = currentPressure - oneHourPressure;
    }

    if (threeHourPressure != null) {
      threeHourChange = currentPressure - threeHourPressure;
    }

    // Determine trend type and strength
    WeatherTrendType newTrend;
    double strength;

    // Use 3-hour change as primary indicator, 1-hour as secondary
    final primaryChange =
        threeHourChange != 0.0 ? threeHourChange : oneHourChange;

    if (primaryChange > 1.0) {
      newTrend = WeatherTrendType.rising;
      strength = math.min(1.0, primaryChange / 5.0); // Normalize to 0-1
    } else if (primaryChange < -1.0) {
      newTrend = WeatherTrendType.falling;
      strength = math.min(1.0, (-primaryChange) / 5.0); // Normalize to 0-1
    } else {
      newTrend = WeatherTrendType.stable;
      strength = 1.0 - math.min(1.0, primaryChange.abs());
    }

    // Update trend if changed significantly
    if (newTrend != _currentTrend || (strength - _trendStrength).abs() > 0.2) {
      _currentTrend = newTrend;
      _trendStrength = strength;
      debugPrint(
          'Updated pressure trend: $_currentTrend (strength: $_trendStrength)');

      final weatherTrend = WeatherTrend(
        trend: newTrend,
        strength: strength,
        oneHourChange: oneHourChange,
        threeHourChange: threeHourChange,
        currentPressure: currentPressure,
        timestamp: DateTime.now(),
      );

      _weatherController?.add(weatherTrend);

      debugPrint(
          '🌡️ Weather trend: ${newTrend.description} (strength: ${(strength * 100).round()}%)');
      debugPrint('  1h change: ${oneHourChange.toStringAsFixed(2)} hPa');
      debugPrint('  3h change: ${threeHourChange.toStringAsFixed(2)} hPa');
    }
  }

  /// Get weather forecast based on pressure trend
  WeatherForecast getWeatherForecast() {
    switch (_currentTrend) {
      case WeatherTrendType.rising:
        if (_trendStrength > 0.7) {
          return WeatherForecast.clearingRapidly;
        } else if (_trendStrength > 0.4) {
          return WeatherForecast.improving;
        } else {
          return WeatherForecast.stable;
        }

      case WeatherTrendType.falling:
        if (_trendStrength > 0.7) {
          return WeatherForecast.stormApproaching;
        } else if (_trendStrength > 0.4) {
          return WeatherForecast.deteriorating;
        } else {
          return WeatherForecast.stable;
        }

      case WeatherTrendType.stable:
        return WeatherForecast.stable;
    }
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}

/// Pressure reading with altitude and weather information
class PressureReading {
  const PressureReading({
    required this.rawPressure,
    required this.filteredPressure,
    required this.altitude,
    required this.altitudeAccuracy,
    required this.timestamp,
    required this.isCalibrated,
    required this.referencePressure,
    required this.weatherTrend,
    required this.trendStrength,
  });

  final double rawPressure;
  final double filteredPressure;
  final double altitude;
  final double altitudeAccuracy;
  final DateTime timestamp;
  final bool isCalibrated;
  final double referencePressure;
  final WeatherTrendType weatherTrend;
  final double trendStrength;
}

/// Altitude change event
class AltitudeEvent {
  const AltitudeEvent({
    required this.altitude,
    required this.change,
    required this.accuracy,
    required this.timestamp,
    required this.isCalibrated,
  });

  final double altitude;
  final double change;
  final double accuracy;
  final DateTime timestamp;
  final bool isCalibrated;
}

/// Weather trend information
class WeatherTrend {
  const WeatherTrend({
    required this.trend,
    required this.strength,
    required this.oneHourChange,
    required this.threeHourChange,
    required this.currentPressure,
    required this.timestamp,
  });

  final WeatherTrendType trend;
  final double strength;
  final double oneHourChange;
  final double threeHourChange;
  final double currentPressure;
  final DateTime timestamp;
}

/// Pressure data point for history
class PressureDataPoint {
  const PressureDataPoint({
    required this.pressure,
    required this.timestamp,
  });

  final double pressure;
  final DateTime timestamp;
}

/// Types of weather trends
enum WeatherTrendType {
  rising,
  falling,
  stable;

  String get description {
    switch (this) {
      case WeatherTrendType.rising:
        return 'Rising';
      case WeatherTrendType.falling:
        return 'Falling';
      case WeatherTrendType.stable:
        return 'Stable';
    }
  }
}

/// Weather forecast based on pressure trends
enum WeatherForecast {
  clearingRapidly,
  improving,
  stable,
  deteriorating,
  stormApproaching;

  String get description {
    switch (this) {
      case WeatherForecast.clearingRapidly:
        return 'Clearing Rapidly';
      case WeatherForecast.improving:
        return 'Improving';
      case WeatherForecast.stable:
        return 'Stable';
      case WeatherForecast.deteriorating:
        return 'Deteriorating';
      case WeatherForecast.stormApproaching:
        return 'Storm Approaching';
    }
  }
}
