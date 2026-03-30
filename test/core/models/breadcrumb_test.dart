import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';

void main() {
  group('Breadcrumb', () {
    late DateTime testDateTime;
    late LatLng testCoordinates;
    late Map<String, dynamic> testMap;

    setUp(() {
      testDateTime = DateTime(2024, 1, 15, 10, 30);
      testCoordinates = const LatLng(40.7128, -74.0060);
      testMap = {
        'id': 'breadcrumb-123',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'altitude': 100.5,
        'accuracy': 5.0,
        'speed': 2.5,
        'heading': 180.0,
        'timestamp': testDateTime.millisecondsSinceEpoch,
        'session_id': 'session-456',
      };
    });

    group('Constructor', () {
      test('creates instance with required parameters', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(breadcrumb.id, equals('test-123'));
        expect(breadcrumb.coordinates, equals(testCoordinates));
        expect(breadcrumb.accuracy, equals(5.0));
        expect(breadcrumb.timestamp, equals(testDateTime));
        expect(breadcrumb.sessionId, equals('session-456'));
        expect(breadcrumb.altitude, isNull);
        expect(breadcrumb.speed, isNull);
        expect(breadcrumb.heading, isNull);
      });

      test('creates instance with all parameters', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
          altitude: 100.5,
          speed: 2.5,
          heading: 180.0,
        );

        expect(breadcrumb.altitude, equals(100.5));
        expect(breadcrumb.speed, equals(2.5));
        expect(breadcrumb.heading, equals(180.0));
      });
    });

    group('Factory constructors', () {
      test('fromPosition() creates breadcrumb from GPS position data', () {
        final breadcrumb = Breadcrumb.fromPosition(
          id: 'test-123',
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 3.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
          altitude: 150.0,
          speed: 1.5,
          heading: 90.0,
        );

        expect(breadcrumb.id, equals('test-123'));
        expect(breadcrumb.coordinates.latitude, equals(40.7128));
        expect(breadcrumb.coordinates.longitude, equals(-74.0060));
        expect(breadcrumb.accuracy, equals(3.0));
        expect(breadcrumb.timestamp, equals(testDateTime));
        expect(breadcrumb.sessionId, equals('session-456'));
        expect(breadcrumb.altitude, equals(150.0));
        expect(breadcrumb.speed, equals(1.5));
        expect(breadcrumb.heading, equals(90.0));
      });

      test('fromPosition() handles null optional parameters', () {
        final breadcrumb = Breadcrumb.fromPosition(
          id: 'test-123',
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(breadcrumb.altitude, isNull);
        expect(breadcrumb.speed, isNull);
        expect(breadcrumb.heading, isNull);
      });

      test('fromMap() creates breadcrumb from database map', () {
        final breadcrumb = Breadcrumb.fromMap(testMap);

        expect(breadcrumb.id, equals('breadcrumb-123'));
        expect(breadcrumb.coordinates.latitude, equals(40.7128));
        expect(breadcrumb.coordinates.longitude, equals(-74.0060));
        expect(breadcrumb.altitude, equals(100.5));
        expect(breadcrumb.accuracy, equals(5.0));
        expect(breadcrumb.speed, equals(2.5));
        expect(breadcrumb.heading, equals(180.0));
        expect(breadcrumb.timestamp, equals(testDateTime));
        expect(breadcrumb.sessionId, equals('session-456'));
      });

      test('fromMap() handles null optional fields', () {
        final mapWithNulls = {
          'id': 'breadcrumb-123',
          'latitude': 40.7128,
          'longitude': -74.0060,
          'altitude': null,
          'accuracy': 5.0,
          'speed': null,
          'heading': null,
          'timestamp': testDateTime.millisecondsSinceEpoch,
          'session_id': 'session-456',
        };

        final breadcrumb = Breadcrumb.fromMap(mapWithNulls);
        expect(breadcrumb.altitude, isNull);
        expect(breadcrumb.speed, isNull);
        expect(breadcrumb.heading, isNull);
        expect(breadcrumb.accuracy, equals(5.0)); // Required field
      });
    });

    group('toMap()', () {
      test('converts breadcrumb to map correctly', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 8.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
          altitude: 200.0,
          speed: 3.0,
          heading: 270.0,
        );

        final map = breadcrumb.toMap();

        expect(map['id'], equals('test-123'));
        expect(map['latitude'], equals(40.7128));
        expect(map['longitude'], equals(-74.0060));
        expect(map['altitude'], equals(200.0));
        expect(map['accuracy'], equals(8.0));
        expect(map['speed'], equals(3.0));
        expect(map['heading'], equals(270.0));
        expect(map['timestamp'], equals(testDateTime.millisecondsSinceEpoch));
        expect(map['session_id'], equals('session-456'));
      });

      test('handles null optional fields in toMap()', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final map = breadcrumb.toMap();

        expect(map['altitude'], isNull);
        expect(map['speed'], isNull);
        expect(map['heading'], isNull);
        // Required fields should still be present
        expect(map['id'], equals('test-123'));
        expect(map['accuracy'], equals(5.0));
      });
    });

    group('Distance calculations', () {
      test('distanceTo calculates distance between breadcrumbs', () {
        final breadcrumb1 = Breadcrumb(
          id: 'test-1',
          coordinates: const LatLng(40.7128, -74.0060), // NYC
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final breadcrumb2 = Breadcrumb(
          id: 'test-2',
          coordinates: const LatLng(40.7589, -73.9851), // Times Square
          accuracy: 5.0,
          timestamp: testDateTime.add(const Duration(minutes: 5)),
          sessionId: 'session-456',
        );

        final distance = breadcrumb1.distanceTo(breadcrumb2);
        expect(distance, greaterThan(0));
        expect(distance, lessThan(10000)); // Should be less than 10km
      });

      test('distanceTo returns 0 for same coordinates', () {
        final breadcrumb1 = Breadcrumb(
          id: 'test-1',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final breadcrumb2 = Breadcrumb(
          id: 'test-2',
          coordinates: testCoordinates, // Same coordinates
          accuracy: 5.0,
          timestamp: testDateTime.add(const Duration(minutes: 5)),
          sessionId: 'session-456',
        );

        final distance = breadcrumb1.distanceTo(breadcrumb2);
        expect(distance, closeTo(0.0, 0.1));
      });

      test('distance calculations are symmetric', () {
        final breadcrumb1 = Breadcrumb(
          id: 'test-1',
          coordinates: const LatLng(40.7128, -74.0060),
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final breadcrumb2 = Breadcrumb(
          id: 'test-2',
          coordinates: const LatLng(40.7589, -73.9851),
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final distance1 = breadcrumb1.distanceTo(breadcrumb2);
        final distance2 = breadcrumb2.distanceTo(breadcrumb1);

        expect(distance1, closeTo(distance2, 0.1));
      });
    });

    group('Accuracy properties', () {
      test('hasGoodAccuracy returns true for accuracy <= 10.0', () {
        final goodAccuracyBreadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final excellentAccuracyBreadcrumb =
            goodAccuracyBreadcrumb.copyWith(accuracy: 3.0);
        final borderlineAccuracyBreadcrumb =
            goodAccuracyBreadcrumb.copyWith(accuracy: 10.0);

        expect(goodAccuracyBreadcrumb.hasGoodAccuracy, isTrue);
        expect(excellentAccuracyBreadcrumb.hasGoodAccuracy, isTrue);
        expect(borderlineAccuracyBreadcrumb.hasGoodAccuracy, isTrue);
      });

      test('hasGoodAccuracy returns false for accuracy > 10.0', () {
        final poorAccuracyBreadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 15.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final veryPoorAccuracyBreadcrumb =
            poorAccuracyBreadcrumb.copyWith(accuracy: 25.0);

        expect(poorAccuracyBreadcrumb.hasGoodAccuracy, isFalse);
        expect(veryPoorAccuracyBreadcrumb.hasGoodAccuracy, isFalse);
      });

      test('accuracyDescription returns correct descriptions', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(breadcrumb.copyWith(accuracy: 2.0).accuracyDescription,
            equals('Excellent'));
        expect(breadcrumb.copyWith(accuracy: 3.0).accuracyDescription,
            equals('Excellent'));
        expect(breadcrumb.copyWith(accuracy: 4.0).accuracyDescription,
            equals('Good'));
        expect(breadcrumb.copyWith(accuracy: 5.0).accuracyDescription,
            equals('Good'));
        expect(breadcrumb.copyWith(accuracy: 8.0).accuracyDescription,
            equals('Fair'));
        expect(breadcrumb.copyWith(accuracy: 10.0).accuracyDescription,
            equals('Fair'));
        expect(breadcrumb.copyWith(accuracy: 15.0).accuracyDescription,
            equals('Poor'));
        expect(breadcrumb.copyWith(accuracy: 20.0).accuracyDescription,
            equals('Poor'));
        expect(breadcrumb.copyWith(accuracy: 25.0).accuracyDescription,
            equals('Very Poor'));
        expect(breadcrumb.copyWith(accuracy: 50.0).accuracyDescription,
            equals('Very Poor'));
      });

      test('accuracyDescription boundary conditions', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        // Test exact boundary values
        expect(breadcrumb.copyWith(accuracy: 3.0).accuracyDescription,
            equals('Excellent'));
        expect(breadcrumb.copyWith(accuracy: 3.1).accuracyDescription,
            equals('Good'));
        expect(breadcrumb.copyWith(accuracy: 5.0).accuracyDescription,
            equals('Good'));
        expect(breadcrumb.copyWith(accuracy: 5.1).accuracyDescription,
            equals('Fair'));
        expect(breadcrumb.copyWith(accuracy: 10.0).accuracyDescription,
            equals('Fair'));
        expect(breadcrumb.copyWith(accuracy: 10.1).accuracyDescription,
            equals('Poor'));
        expect(breadcrumb.copyWith(accuracy: 20.0).accuracyDescription,
            equals('Poor'));
        expect(breadcrumb.copyWith(accuracy: 20.1).accuracyDescription,
            equals('Very Poor'));
      });
    });

    group('Equality and hashCode', () {
      test('equality is based on id', () {
        final breadcrumb1 = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final breadcrumb2 = Breadcrumb(
          id: 'test-123',
          coordinates: const LatLng(50.0, 50.0), // Different coordinates
          accuracy: 10.0, // Different accuracy
          timestamp:
              testDateTime.add(const Duration(hours: 1)), // Different time
          sessionId: 'session-789', // Different session
        );

        final breadcrumb3 = Breadcrumb(
          id: 'test-456',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(breadcrumb1, equals(breadcrumb2)); // Same ID
        expect(breadcrumb1, isNot(equals(breadcrumb3))); // Different ID
      });

      test('hashCode is based on id', () {
        final breadcrumb1 = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final breadcrumb2 = Breadcrumb(
          id: 'test-123',
          coordinates: const LatLng(50.0, 50.0),
          accuracy: 10.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(breadcrumb1.hashCode, equals(breadcrumb2.hashCode));
      });
    });

    group('toString()', () {
      test('returns formatted string representation', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
          altitude: 100.0,
          speed: 2.5,
          heading: 180.0,
        );

        final result = breadcrumb.toString();
        expect(result, contains('test-123'));
        expect(result, contains('40.7128'));
        expect(result, contains('-74.006'));
        expect(result, contains('5.0m'));
        expect(result, contains(testDateTime.toString()));
      });

      test('includes all coordinate information', () {
        final breadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: const LatLng(40.7128, -74.0060),
          accuracy: 8.5,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final result = breadcrumb.toString();
        expect(result, contains('40.7128'));
        expect(result, contains('-74.006'));
        expect(result, contains('8.5m'));
      });
    });

    group('copyWith()', () {
      late Breadcrumb originalBreadcrumb;

      setUp(() {
        originalBreadcrumb = Breadcrumb(
          id: 'test-123',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
          altitude: 100.0,
          speed: 2.0,
          heading: 180.0,
        );
      });

      test('returns identical breadcrumb when no parameters provided', () {
        final copied = originalBreadcrumb.copyWith();

        expect(copied.id, equals(originalBreadcrumb.id));
        expect(copied.coordinates, equals(originalBreadcrumb.coordinates));
        expect(copied.accuracy, equals(originalBreadcrumb.accuracy));
        expect(copied.timestamp, equals(originalBreadcrumb.timestamp));
        expect(copied.sessionId, equals(originalBreadcrumb.sessionId));
        expect(copied.altitude, equals(originalBreadcrumb.altitude));
        expect(copied.speed, equals(originalBreadcrumb.speed));
        expect(copied.heading, equals(originalBreadcrumb.heading));
      });

      test('updates only specified parameters', () {
        const newCoordinates = LatLng(50.0, 50.0);
        final newDateTime = testDateTime.add(const Duration(hours: 1));

        final copied = originalBreadcrumb.copyWith(
          coordinates: newCoordinates,
          accuracy: 10.0,
          timestamp: newDateTime,
          altitude: 200.0,
        );

        expect(copied.coordinates, equals(newCoordinates));
        expect(copied.accuracy, equals(10.0));
        expect(copied.timestamp, equals(newDateTime));
        expect(copied.altitude, equals(200.0));
        // Unchanged values
        expect(copied.id, equals(originalBreadcrumb.id));
        expect(copied.sessionId, equals(originalBreadcrumb.sessionId));
        expect(copied.speed, equals(originalBreadcrumb.speed));
        expect(copied.heading, equals(originalBreadcrumb.heading));
      });

      test('can update all parameters', () {
        const newCoordinates = LatLng(50.0, 50.0);
        final newDateTime = testDateTime.add(const Duration(hours: 1));

        final copied = originalBreadcrumb.copyWith(
          id: 'new-id',
          coordinates: newCoordinates,
          altitude: 300.0,
          accuracy: 15.0,
          speed: 5.0,
          heading: 90.0,
          timestamp: newDateTime,
          sessionId: 'new-session',
        );

        expect(copied.id, equals('new-id'));
        expect(copied.coordinates, equals(newCoordinates));
        expect(copied.altitude, equals(300.0));
        expect(copied.accuracy, equals(15.0));
        expect(copied.speed, equals(5.0));
        expect(copied.heading, equals(90.0));
        expect(copied.timestamp, equals(newDateTime));
        expect(copied.sessionId, equals('new-session'));
      });

      test('preserves existing values when no parameters provided', () {
        final copied = originalBreadcrumb.copyWith();

        // All values should remain unchanged
        expect(copied.altitude, equals(originalBreadcrumb.altitude));
        expect(copied.speed, equals(originalBreadcrumb.speed));
        expect(copied.heading, equals(originalBreadcrumb.heading));
        expect(copied.id, equals(originalBreadcrumb.id));
        expect(copied.coordinates, equals(originalBreadcrumb.coordinates));
        expect(copied.accuracy, equals(originalBreadcrumb.accuracy));
      });
    });

    group('Edge cases and validation', () {
      test('handles extreme coordinate values', () {
        final extremeBreadcrumb = Breadcrumb(
          id: 'extreme-test',
          coordinates:
              const LatLng(90.0, 180.0), // North pole, international date line
          accuracy: 1.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(extremeBreadcrumb.coordinates.latitude, equals(90.0));
        expect(extremeBreadcrumb.coordinates.longitude, equals(180.0));
        expect(extremeBreadcrumb.hasGoodAccuracy, isTrue);
      });

      test('handles zero accuracy', () {
        final zeroBreadcrumb = Breadcrumb(
          id: 'zero-test',
          coordinates: testCoordinates,
          accuracy: 0.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(zeroBreadcrumb.accuracy, equals(0.0));
        expect(zeroBreadcrumb.hasGoodAccuracy, isTrue);
        expect(zeroBreadcrumb.accuracyDescription, equals('Excellent'));
      });

      test('handles very high accuracy values', () {
        final highAccuracyBreadcrumb = Breadcrumb(
          id: 'high-accuracy-test',
          coordinates: testCoordinates,
          accuracy: 1000.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(highAccuracyBreadcrumb.accuracy, equals(1000.0));
        expect(highAccuracyBreadcrumb.hasGoodAccuracy, isFalse);
        expect(highAccuracyBreadcrumb.accuracyDescription, equals('Very Poor'));
      });

      test('handles negative speed values', () {
        final negativeBreadcrumb = Breadcrumb(
          id: 'negative-test',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
          speed: -1.0,
        );

        expect(negativeBreadcrumb.speed, equals(-1.0));
        // The model should accept negative values (GPS can report negative speeds)
      });

      test('handles heading values outside 0-360 range', () {
        final invalidHeadingBreadcrumb = Breadcrumb(
          id: 'invalid-heading-test',
          coordinates: testCoordinates,
          accuracy: 5.0,
          timestamp: testDateTime,
          sessionId: 'session-456',
          heading: 450.0, // Invalid heading
        );

        expect(invalidHeadingBreadcrumb.heading, equals(450.0));
        // The model should store the value as-is, validation should be done elsewhere
      });
    });
  });
}
