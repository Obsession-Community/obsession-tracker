import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Types of measurements
enum MeasurementType {
  /// Distance between two points
  distance,

  /// Area of a polygon
  area,

  /// Perimeter of a polygon
  perimeter,

  /// Bearing/direction between two points
  bearing,

  /// Elevation difference
  elevation,

  /// Speed calculation
  speed,
}

/// Units for distance measurements
enum DistanceUnit {
  meters,
  kilometers,
  feet,
  miles,
  nauticalMiles,
}

/// Units for area measurements
enum AreaUnit {
  squareMeters,
  squareKilometers,
  squareFeet,
  acres,
  hectares,
}

/// Units for speed measurements
enum SpeedUnit {
  metersPerSecond,
  kilometersPerHour,
  milesPerHour,
  knots,
}

/// Measurement result
@immutable
class MeasurementResult {
  const MeasurementResult({
    required this.type,
    required this.value,
    required this.unit,
    required this.formattedValue,
    this.points = const [],
    this.metadata = const {},
  });

  final MeasurementType type;
  final double value;
  final String unit;
  final String formattedValue;
  final List<LatLng> points;
  final Map<String, dynamic> metadata;

  MeasurementResult copyWith({
    MeasurementType? type,
    double? value,
    String? unit,
    String? formattedValue,
    List<LatLng>? points,
    Map<String, dynamic>? metadata,
  }) =>
      MeasurementResult(
        type: type ?? this.type,
        value: value ?? this.value,
        unit: unit ?? this.unit,
        formattedValue: formattedValue ?? this.formattedValue,
        points: points ?? this.points,
        metadata: metadata ?? this.metadata,
      );
}

/// Service for map measurement tools
class MeasurementToolsService {
  factory MeasurementToolsService() =>
      _instance ??= MeasurementToolsService._();
  MeasurementToolsService._();
  static MeasurementToolsService? _instance;

  final Distance _distance = const Distance();

  // Default units
  DistanceUnit defaultDistanceUnit = DistanceUnit.meters;
  AreaUnit defaultAreaUnit = AreaUnit.squareMeters;
  SpeedUnit defaultSpeedUnit = SpeedUnit.kilometersPerHour;

  /// Measure distance between two points
  MeasurementResult measureDistance(
    LatLng point1,
    LatLng point2, {
    DistanceUnit? unit,
  }) {
    final DistanceUnit measurementUnit = unit ?? defaultDistanceUnit;

    // Calculate distance in meters
    final double distanceInMeters = _distance.as(
      LengthUnit.Meter,
      point1,
      point2,
    );

    // Convert to requested unit
    final double convertedDistance = _convertDistance(
      distanceInMeters,
      DistanceUnit.meters,
      measurementUnit,
    );

    final String formattedValue =
        _formatDistance(convertedDistance, measurementUnit);

    return MeasurementResult(
      type: MeasurementType.distance,
      value: convertedDistance,
      unit: _getDistanceUnitSymbol(measurementUnit),
      formattedValue: formattedValue,
      points: [point1, point2],
      metadata: {
        'distanceInMeters': distanceInMeters,
        'startPoint': {'lat': point1.latitude, 'lng': point1.longitude},
        'endPoint': {'lat': point2.latitude, 'lng': point2.longitude},
      },
    );
  }

  /// Measure total distance along a path
  MeasurementResult measurePathDistance(
    List<LatLng> points, {
    DistanceUnit? unit,
  }) {
    if (points.length < 2) {
      return MeasurementResult(
        type: MeasurementType.distance,
        value: 0.0,
        unit: _getDistanceUnitSymbol(unit ?? defaultDistanceUnit),
        formattedValue:
            '0.0 ${_getDistanceUnitSymbol(unit ?? defaultDistanceUnit)}',
        points: points,
      );
    }

    final DistanceUnit measurementUnit = unit ?? defaultDistanceUnit;
    double totalDistanceInMeters = 0.0;

    // Calculate total distance
    for (int i = 0; i < points.length - 1; i++) {
      totalDistanceInMeters += _distance.as(
        LengthUnit.Meter,
        points[i],
        points[i + 1],
      );
    }

    // Convert to requested unit
    final double convertedDistance = _convertDistance(
      totalDistanceInMeters,
      DistanceUnit.meters,
      measurementUnit,
    );

    final String formattedValue =
        _formatDistance(convertedDistance, measurementUnit);

    return MeasurementResult(
      type: MeasurementType.distance,
      value: convertedDistance,
      unit: _getDistanceUnitSymbol(measurementUnit),
      formattedValue: formattedValue,
      points: points,
      metadata: {
        'distanceInMeters': totalDistanceInMeters,
        'segmentCount': points.length - 1,
        'waypoints':
            points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      },
    );
  }

  /// Measure area of a polygon
  MeasurementResult measureArea(
    List<LatLng> points, {
    AreaUnit? unit,
  }) {
    if (points.length < 3) {
      return MeasurementResult(
        type: MeasurementType.area,
        value: 0.0,
        unit: _getAreaUnitSymbol(unit ?? defaultAreaUnit),
        formattedValue: '0.0 ${_getAreaUnitSymbol(unit ?? defaultAreaUnit)}',
        points: points,
      );
    }

    final AreaUnit measurementUnit = unit ?? defaultAreaUnit;

    // Calculate area using spherical excess formula for accuracy
    final double areaInSquareMeters = _calculateSphericalArea(points);

    // Convert to requested unit
    final double convertedArea = _convertArea(
      areaInSquareMeters,
      AreaUnit.squareMeters,
      measurementUnit,
    );

    final String formattedValue = _formatArea(convertedArea, measurementUnit);

    return MeasurementResult(
      type: MeasurementType.area,
      value: convertedArea,
      unit: _getAreaUnitSymbol(measurementUnit),
      formattedValue: formattedValue,
      points: points,
      metadata: {
        'areaInSquareMeters': areaInSquareMeters,
        'vertexCount': points.length,
        'vertices':
            points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      },
    );
  }

  /// Measure perimeter of a polygon
  MeasurementResult measurePerimeter(
    List<LatLng> points, {
    DistanceUnit? unit,
  }) {
    if (points.length < 2) {
      return MeasurementResult(
        type: MeasurementType.perimeter,
        value: 0.0,
        unit: _getDistanceUnitSymbol(unit ?? defaultDistanceUnit),
        formattedValue:
            '0.0 ${_getDistanceUnitSymbol(unit ?? defaultDistanceUnit)}',
        points: points,
      );
    }

    final DistanceUnit measurementUnit = unit ?? defaultDistanceUnit;
    double perimeterInMeters = 0.0;

    // Calculate perimeter (including closing edge for polygons)
    for (int i = 0; i < points.length; i++) {
      final int nextIndex = (i + 1) % points.length;
      perimeterInMeters += _distance.as(
        LengthUnit.Meter,
        points[i],
        points[nextIndex],
      );
    }

    // Convert to requested unit
    final double convertedPerimeter = _convertDistance(
      perimeterInMeters,
      DistanceUnit.meters,
      measurementUnit,
    );

    final String formattedValue =
        _formatDistance(convertedPerimeter, measurementUnit);

    return MeasurementResult(
      type: MeasurementType.perimeter,
      value: convertedPerimeter,
      unit: _getDistanceUnitSymbol(measurementUnit),
      formattedValue: formattedValue,
      points: points,
      metadata: {
        'perimeterInMeters': perimeterInMeters,
        'vertexCount': points.length,
        'vertices':
            points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      },
    );
  }

  /// Calculate bearing between two points
  MeasurementResult measureBearing(LatLng point1, LatLng point2) {
    final double bearing = _distance.bearing(point1, point2);
    final String compassDirection = _getCompassDirection(bearing);

    return MeasurementResult(
      type: MeasurementType.bearing,
      value: bearing,
      unit: '°',
      formattedValue: '${bearing.toStringAsFixed(1)}° ($compassDirection)',
      points: [point1, point2],
      metadata: {
        'bearingDegrees': bearing,
        'compassDirection': compassDirection,
        'startPoint': {'lat': point1.latitude, 'lng': point1.longitude},
        'endPoint': {'lat': point2.latitude, 'lng': point2.longitude},
      },
    );
  }

  /// Calculate speed between two points with time
  MeasurementResult measureSpeed(
    LatLng point1,
    LatLng point2,
    Duration timeDifference, {
    SpeedUnit? unit,
  }) {
    final SpeedUnit measurementUnit = unit ?? defaultSpeedUnit;

    // Calculate distance in meters
    final double distanceInMeters = _distance.as(
      LengthUnit.Meter,
      point1,
      point2,
    );

    // Calculate speed in m/s
    final double timeInSeconds = timeDifference.inMilliseconds / 1000.0;
    final double speedInMps =
        timeInSeconds > 0 ? distanceInMeters / timeInSeconds : 0.0;

    // Convert to requested unit
    final double convertedSpeed = _convertSpeed(
      speedInMps,
      SpeedUnit.metersPerSecond,
      measurementUnit,
    );

    final String formattedValue = _formatSpeed(convertedSpeed, measurementUnit);

    return MeasurementResult(
      type: MeasurementType.speed,
      value: convertedSpeed,
      unit: _getSpeedUnitSymbol(measurementUnit),
      formattedValue: formattedValue,
      points: [point1, point2],
      metadata: {
        'speedInMps': speedInMps,
        'distanceInMeters': distanceInMeters,
        'timeInSeconds': timeInSeconds,
        'startPoint': {'lat': point1.latitude, 'lng': point1.longitude},
        'endPoint': {'lat': point2.latitude, 'lng': point2.longitude},
      },
    );
  }

  /// Calculate spherical area using spherical excess formula
  double _calculateSphericalArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    const double earthRadius = 6371000; // Earth radius in meters
    double area = 0.0;

    // Convert to radians and calculate spherical excess
    final List<double> lats =
        points.map((p) => p.latitude * math.pi / 180).toList();
    final List<double> lngs =
        points.map((p) => p.longitude * math.pi / 180).toList();

    // Use shoelace formula adapted for spherical coordinates
    for (int i = 0; i < points.length; i++) {
      final int j = (i + 1) % points.length;
      area += (lngs[j] - lngs[i]) * (2 + math.sin(lats[i]) + math.sin(lats[j]));
    }

    area = area.abs() * earthRadius * earthRadius / 2;
    return area;
  }

  /// Convert distance between units
  double _convertDistance(double value, DistanceUnit from, DistanceUnit to) {
    if (from == to) return value;

    // Convert to meters first
    double meters = value;
    switch (from) {
      case DistanceUnit.meters:
        break;
      case DistanceUnit.kilometers:
        meters = value * 1000;
        break;
      case DistanceUnit.feet:
        meters = value * 0.3048;
        break;
      case DistanceUnit.miles:
        meters = value * 1609.344;
        break;
      case DistanceUnit.nauticalMiles:
        meters = value * 1852;
        break;
    }

    // Convert from meters to target unit
    switch (to) {
      case DistanceUnit.meters:
        return meters;
      case DistanceUnit.kilometers:
        return meters / 1000;
      case DistanceUnit.feet:
        return meters / 0.3048;
      case DistanceUnit.miles:
        return meters / 1609.344;
      case DistanceUnit.nauticalMiles:
        return meters / 1852;
    }
  }

  /// Convert area between units
  double _convertArea(double value, AreaUnit from, AreaUnit to) {
    if (from == to) return value;

    // Convert to square meters first
    double squareMeters = value;
    switch (from) {
      case AreaUnit.squareMeters:
        break;
      case AreaUnit.squareKilometers:
        squareMeters = value * 1000000;
        break;
      case AreaUnit.squareFeet:
        squareMeters = value * 0.092903;
        break;
      case AreaUnit.acres:
        squareMeters = value * 4046.86;
        break;
      case AreaUnit.hectares:
        squareMeters = value * 10000;
        break;
    }

    // Convert from square meters to target unit
    switch (to) {
      case AreaUnit.squareMeters:
        return squareMeters;
      case AreaUnit.squareKilometers:
        return squareMeters / 1000000;
      case AreaUnit.squareFeet:
        return squareMeters / 0.092903;
      case AreaUnit.acres:
        return squareMeters / 4046.86;
      case AreaUnit.hectares:
        return squareMeters / 10000;
    }
  }

  /// Convert speed between units
  double _convertSpeed(double value, SpeedUnit from, SpeedUnit to) {
    if (from == to) return value;

    // Convert to m/s first
    double mps = value;
    switch (from) {
      case SpeedUnit.metersPerSecond:
        break;
      case SpeedUnit.kilometersPerHour:
        mps = value / 3.6;
        break;
      case SpeedUnit.milesPerHour:
        mps = value * 0.44704;
        break;
      case SpeedUnit.knots:
        mps = value * 0.514444;
        break;
    }

    // Convert from m/s to target unit
    switch (to) {
      case SpeedUnit.metersPerSecond:
        return mps;
      case SpeedUnit.kilometersPerHour:
        return mps * 3.6;
      case SpeedUnit.milesPerHour:
        return mps / 0.44704;
      case SpeedUnit.knots:
        return mps / 0.514444;
    }
  }

  /// Format distance value
  String _formatDistance(double value, DistanceUnit unit) {
    if (value < 1 && unit != DistanceUnit.meters) {
      // Show in smaller units for small values
      switch (unit) {
        case DistanceUnit.kilometers:
          return '${(value * 1000).toStringAsFixed(0)} m';
        case DistanceUnit.miles:
          return '${(value * 5280).toStringAsFixed(0)} ft';
        default:
          break;
      }
    }

    final String unitSymbol = _getDistanceUnitSymbol(unit);
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} k$unitSymbol';
    } else if (value >= 1) {
      return '${value.toStringAsFixed(2)} $unitSymbol';
    } else {
      return '${value.toStringAsFixed(3)} $unitSymbol';
    }
  }

  /// Format area value
  String _formatArea(double value, AreaUnit unit) {
    final String unitSymbol = _getAreaUnitSymbol(unit);

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} M$unitSymbol';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} k$unitSymbol';
    } else if (value >= 1) {
      return '${value.toStringAsFixed(2)} $unitSymbol';
    } else {
      return '${value.toStringAsFixed(3)} $unitSymbol';
    }
  }

  /// Format speed value
  String _formatSpeed(double value, SpeedUnit unit) {
    final String unitSymbol = _getSpeedUnitSymbol(unit);
    return '${value.toStringAsFixed(1)} $unitSymbol';
  }

  /// Get distance unit symbol
  String _getDistanceUnitSymbol(DistanceUnit unit) {
    switch (unit) {
      case DistanceUnit.meters:
        return 'm';
      case DistanceUnit.kilometers:
        return 'km';
      case DistanceUnit.feet:
        return 'ft';
      case DistanceUnit.miles:
        return 'mi';
      case DistanceUnit.nauticalMiles:
        return 'nmi';
    }
  }

  /// Get area unit symbol
  String _getAreaUnitSymbol(AreaUnit unit) {
    switch (unit) {
      case AreaUnit.squareMeters:
        return 'm²';
      case AreaUnit.squareKilometers:
        return 'km²';
      case AreaUnit.squareFeet:
        return 'ft²';
      case AreaUnit.acres:
        return 'ac';
      case AreaUnit.hectares:
        return 'ha';
    }
  }

  /// Get speed unit symbol
  String _getSpeedUnitSymbol(SpeedUnit unit) {
    switch (unit) {
      case SpeedUnit.metersPerSecond:
        return 'm/s';
      case SpeedUnit.kilometersPerHour:
        return 'km/h';
      case SpeedUnit.milesPerHour:
        return 'mph';
      case SpeedUnit.knots:
        return 'kn';
    }
  }

  /// Get compass direction from bearing
  String _getCompassDirection(double bearing) {
    const List<String> directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];

    final int index = ((bearing + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Get all available distance units
  List<DistanceUnit> get availableDistanceUnits => DistanceUnit.values;

  /// Get all available area units
  List<AreaUnit> get availableAreaUnits => AreaUnit.values;

  /// Get all available speed units
  List<SpeedUnit> get availableSpeedUnits => SpeedUnit.values;

  /// Dispose of the service
  void dispose() {
    _instance = null;
  }
}
