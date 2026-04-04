import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/core/providers/custom_north_provider.dart';

void main() {
  group('CustomNorthState', () {
    test('default state has empty references and no active reference', () {
      const state = CustomNorthState();

      expect(state.references, isEmpty);
      expect(state.activeReference, isNull);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('equality works correctly', () {
      const a = CustomNorthState();
      const b = CustomNorthState();
      const c = CustomNorthState(isLoading: true);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('CustomNorthNotifier static methods', () {
    test(
        'calculateBearingToTarget returns correct bearing for known coordinates',
        () {
      // New York to London: approximately 51° bearing
      final bearing = CustomNorthNotifier.calculateBearingToTarget(
        40.7128, -74.0060, // New York
        51.5074, -0.1278, // London
      );

      // Bearing should be roughly NE (~51°)
      expect(bearing, greaterThan(45));
      expect(bearing, lessThan(60));
    });

    test('calculateBearingToTarget returns 0 for due north', () {
      // Point directly north: same longitude, higher latitude
      final bearing = CustomNorthNotifier.calculateBearingToTarget(
        40.0, -110.0, // From
        50.0, -110.0, // Due north
      );

      expect(bearing, closeTo(0, 1)); // Should be ~0°
    });

    test('calculateBearingToTarget returns 90 for due east', () {
      // Point directly east: same latitude, higher longitude
      // (approximation — on a sphere, due east at equator is exactly 90°)
      final bearing = CustomNorthNotifier.calculateBearingToTarget(
        0.0, 0.0, // Equator/Prime Meridian
        0.0, 10.0, // Due east
      );

      expect(bearing, closeTo(90, 1));
    });

    test('calculateBearingToTarget returns 180 for due south', () {
      final bearing = CustomNorthNotifier.calculateBearingToTarget(
        50.0,
        -110.0,
        40.0,
        -110.0,
      );

      expect(bearing, closeTo(180, 1));
    });

    test('calculateBearingToTarget returns 270 for due west', () {
      final bearing = CustomNorthNotifier.calculateBearingToTarget(
        0.0,
        0.0,
        0.0,
        -10.0,
      );

      expect(bearing, closeTo(270, 1));
    });

    test('calculateBearingToTarget always returns 0-360 range', () {
      // Various positions should all produce bearings in [0, 360)
      final testCases = [
        [0.0, 0.0, 10.0, 10.0],
        [45.0, -90.0, -45.0, 90.0],
        [-33.8688, 151.2093, 35.6762, 139.6503], // Sydney to Tokyo
      ];

      for (final tc in testCases) {
        final bearing = CustomNorthNotifier.calculateBearingToTarget(
          tc[0],
          tc[1],
          tc[2],
          tc[3],
        );
        expect(bearing, greaterThanOrEqualTo(0));
        expect(bearing, lessThan(360));
      }
    });

    test('calculateDistanceMeters returns correct distance for known points',
        () {
      // New York to Los Angeles: ~3944 km
      final distance = CustomNorthNotifier.calculateDistanceMeters(
        40.7128, -74.0060, // New York
        34.0522, -118.2437, // Los Angeles
      );

      // Should be approximately 3944 km (within 5% tolerance)
      expect(distance / 1000, closeTo(3944, 200));
    });

    test('calculateDistanceMeters returns 0 for same point', () {
      final distance = CustomNorthNotifier.calculateDistanceMeters(
        45.0,
        -110.0,
        45.0,
        -110.0,
      );

      expect(distance, closeTo(0, 0.01));
    });

    test('calculateDistanceMeters is symmetric', () {
      final d1 = CustomNorthNotifier.calculateDistanceMeters(
        40.0,
        -110.0,
        45.0,
        -115.0,
      );
      final d2 = CustomNorthNotifier.calculateDistanceMeters(
        45.0,
        -115.0,
        40.0,
        -110.0,
      );

      expect(d1, closeTo(d2, 0.01));
    });

    test('calculateDistanceMeters returns positive values', () {
      final distance = CustomNorthNotifier.calculateDistanceMeters(
        -33.8688, 151.2093, // Sydney
        51.5074, -0.1278, // London
      );

      expect(distance, greaterThan(0));
    });
  });
}
