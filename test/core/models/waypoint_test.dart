import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

void main() {
  group('WaypointType', () {
    test('has correct enum values', () {
      // Expanded from original 7 to 36 waypoint types (added voice)
      expect(WaypointType.values.length, equals(36));

      // Personal Markers
      expect(WaypointType.values, contains(WaypointType.treasure));
      expect(WaypointType.values, contains(WaypointType.custom));
      expect(WaypointType.values, contains(WaypointType.photo));
      expect(WaypointType.values, contains(WaypointType.note));
      expect(WaypointType.values, contains(WaypointType.voice));
      expect(WaypointType.values, contains(WaypointType.favorite));
      expect(WaypointType.values, contains(WaypointType.memory));
      expect(WaypointType.values, contains(WaypointType.goal));

      // Outdoor Activities
      expect(WaypointType.values, contains(WaypointType.hiking));
      expect(WaypointType.values, contains(WaypointType.climbing));
      expect(WaypointType.values, contains(WaypointType.camp));
      expect(WaypointType.values, contains(WaypointType.fishing));
      expect(WaypointType.values, contains(WaypointType.hunting));
      expect(WaypointType.values, contains(WaypointType.cycling));
      expect(WaypointType.values, contains(WaypointType.kayaking));
      expect(WaypointType.values, contains(WaypointType.skiing));

      // Points of Interest
      expect(WaypointType.values, contains(WaypointType.interest));
      expect(WaypointType.values, contains(WaypointType.viewpoint));
      expect(WaypointType.values, contains(WaypointType.landmark));
      expect(WaypointType.values, contains(WaypointType.waterfall));
      expect(WaypointType.values, contains(WaypointType.cave));
      expect(WaypointType.values, contains(WaypointType.bridge));
      expect(WaypointType.values, contains(WaypointType.ruins));
      expect(WaypointType.values, contains(WaypointType.wildlife));
      expect(WaypointType.values, contains(WaypointType.flora));

      // Facilities & Services
      expect(WaypointType.values, contains(WaypointType.parking));
      expect(WaypointType.values, contains(WaypointType.restroom));
      expect(WaypointType.values, contains(WaypointType.shelter));
      expect(WaypointType.values, contains(WaypointType.waterSource));
      expect(WaypointType.values, contains(WaypointType.fuelStation));
      expect(WaypointType.values, contains(WaypointType.restaurant));
      expect(WaypointType.values, contains(WaypointType.lodging));

      // Safety & Navigation
      expect(WaypointType.values, contains(WaypointType.warning));
      expect(WaypointType.values, contains(WaypointType.danger));
      expect(WaypointType.values, contains(WaypointType.emergency));
      expect(WaypointType.values, contains(WaypointType.firstAid));
    });

    group('WaypointTypeExtension', () {
      test('displayName returns correct values', () {
        expect(WaypointType.treasure.displayName, equals('Treasure'));
        expect(WaypointType.warning.displayName, equals('Warning'));
        expect(WaypointType.camp.displayName, equals('Camp'));
        expect(WaypointType.interest.displayName, equals('Interest'));
        expect(WaypointType.custom.displayName, equals('Custom'));
        expect(WaypointType.photo.displayName, equals('Photo'));
        expect(WaypointType.note.displayName, equals('Note'));
      });

      test('iconName returns correct values', () {
        expect(WaypointType.treasure.iconName, equals('treasure'));
        expect(WaypointType.warning.iconName, equals('warning'));
        expect(WaypointType.camp.iconName, equals('camp'));
        expect(WaypointType.interest.iconName, equals('interest'));
        expect(WaypointType.custom.iconName, equals('custom'));
        expect(WaypointType.photo.iconName, equals('photo'));
        expect(WaypointType.note.iconName, equals('note'));
      });

      test('colorHex returns correct values', () {
        // Personal Markers
        expect(WaypointType.treasure.colorHex, equals('#FFD700'));
        expect(WaypointType.custom.colorHex, equals('#9C27B0'));
        expect(WaypointType.photo.colorHex, equals('#FF6B35'));
        expect(WaypointType.note.colorHex, equals('#00BCD4'));

        // Outdoor Activities
        expect(WaypointType.camp.colorHex, equals('#4CAF50'));
        expect(WaypointType.fishing.colorHex, equals('#03A9F4'));
        expect(WaypointType.hunting.colorHex, equals('#8D6E63'));

        // Points of Interest
        expect(WaypointType.interest.colorHex, equals('#2196F3'));
        expect(WaypointType.viewpoint.colorHex, equals('#3F51B5'));

        // Safety & Navigation (warning is now Amber, not red)
        expect(WaypointType.warning.colorHex, equals('#FF9800'));
        expect(WaypointType.danger.colorHex, equals('#F44336'));
      });
    });
  });

  group('Waypoint', () {
    late DateTime testDateTime;
    late LatLng testCoordinates;
    late Map<String, dynamic> testMap;

    setUp(() {
      testDateTime = DateTime(2024, 1, 15, 10, 30);
      testCoordinates = const LatLng(40.7128, -74.0060);
      testMap = {
        'id': 'waypoint-123',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'type': 'treasure',
        'timestamp': testDateTime.millisecondsSinceEpoch,
        'session_id': 'session-456',
        'name': 'Test Waypoint',
        'notes': 'Test notes',
        'altitude': 100.5,
        'accuracy': 5.0,
        'speed': 2.5,
        'heading': 180.0,
      };
    });

    group('Constructor', () {
      test('creates instance with required parameters', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(waypoint.id, equals('test-123'));
        expect(waypoint.coordinates, equals(testCoordinates));
        expect(waypoint.type, equals(WaypointType.treasure));
        expect(waypoint.timestamp, equals(testDateTime));
        expect(waypoint.sessionId, equals('session-456'));
        expect(waypoint.name, isNull);
        expect(waypoint.notes, isNull);
        expect(waypoint.altitude, isNull);
        expect(waypoint.accuracy, isNull);
        expect(waypoint.speed, isNull);
        expect(waypoint.heading, isNull);
      });

      test('creates instance with all parameters', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Test Waypoint',
          notes: 'Test notes',
          altitude: 100.5,
          accuracy: 5.0,
          speed: 2.5,
          heading: 180.0,
        );

        expect(waypoint.name, equals('Test Waypoint'));
        expect(waypoint.notes, equals('Test notes'));
        expect(waypoint.altitude, equals(100.5));
        expect(waypoint.accuracy, equals(5.0));
        expect(waypoint.speed, equals(2.5));
        expect(waypoint.heading, equals(180.0));
      });
    });

    group('Factory constructors', () {
      test('fromLocation() creates waypoint from location data', () {
        final waypoint = Waypoint.fromLocation(
          id: 'test-123',
          latitude: 40.7128,
          longitude: -74.0060,
          type: WaypointType.camp,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Camp Site',
          notes: 'Good camping spot',
          altitude: 150.0,
          accuracy: 3.0,
          speed: 0.0,
          heading: 90.0,
        );

        expect(waypoint.id, equals('test-123'));
        expect(waypoint.coordinates.latitude, equals(40.7128));
        expect(waypoint.coordinates.longitude, equals(-74.0060));
        expect(waypoint.type, equals(WaypointType.camp));
        expect(waypoint.timestamp, equals(testDateTime));
        expect(waypoint.sessionId, equals('session-456'));
        expect(waypoint.name, equals('Camp Site'));
        expect(waypoint.notes, equals('Good camping spot'));
        expect(waypoint.altitude, equals(150.0));
        expect(waypoint.accuracy, equals(3.0));
        expect(waypoint.speed, equals(0.0));
        expect(waypoint.heading, equals(90.0));
      });

      test('fromMap() creates waypoint from database map', () {
        final waypoint = Waypoint.fromMap(testMap);

        expect(waypoint.id, equals('waypoint-123'));
        expect(waypoint.coordinates.latitude, equals(40.7128));
        expect(waypoint.coordinates.longitude, equals(-74.0060));
        expect(waypoint.type, equals(WaypointType.treasure));
        expect(waypoint.timestamp, equals(testDateTime));
        expect(waypoint.sessionId, equals('session-456'));
        expect(waypoint.name, equals('Test Waypoint'));
        expect(waypoint.notes, equals('Test notes'));
        expect(waypoint.altitude, equals(100.5));
        expect(waypoint.accuracy, equals(5.0));
        expect(waypoint.speed, equals(2.5));
        expect(waypoint.heading, equals(180.0));
      });

      test('fromMap() handles invalid type gracefully', () {
        final mapWithInvalidType = Map<String, dynamic>.from(testMap);
        mapWithInvalidType['type'] = 'invalid_type';

        final waypoint = Waypoint.fromMap(mapWithInvalidType);
        expect(waypoint.type, equals(WaypointType.custom));
      });

      test('fromMap() handles null optional fields', () {
        final mapWithNulls = {
          'id': 'waypoint-123',
          'latitude': 40.7128,
          'longitude': -74.0060,
          'type': 'treasure',
          'timestamp': testDateTime.millisecondsSinceEpoch,
          'session_id': 'session-456',
          'name': null,
          'notes': null,
          'altitude': null,
          'accuracy': null,
          'speed': null,
          'heading': null,
        };

        final waypoint = Waypoint.fromMap(mapWithNulls);
        expect(waypoint.name, isNull);
        expect(waypoint.notes, isNull);
        expect(waypoint.altitude, isNull);
        expect(waypoint.accuracy, isNull);
        expect(waypoint.speed, isNull);
        expect(waypoint.heading, isNull);
      });
    });

    group('toMap()', () {
      test('converts waypoint to map correctly', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.warning,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Danger Zone',
          notes: 'Steep cliff ahead',
          altitude: 200.0,
          accuracy: 8.0,
          speed: 1.5,
          heading: 270.0,
        );

        final map = waypoint.toMap();

        expect(map['id'], equals('test-123'));
        expect(map['latitude'], equals(40.7128));
        expect(map['longitude'], equals(-74.0060));
        expect(map['type'], equals('warning'));
        expect(map['timestamp'], equals(testDateTime.millisecondsSinceEpoch));
        expect(map['session_id'], equals('session-456'));
        expect(map['name'], equals('Danger Zone'));
        expect(map['notes'], equals('Steep cliff ahead'));
        expect(map['altitude'], equals(200.0));
        expect(map['accuracy'], equals(8.0));
        expect(map['speed'], equals(1.5));
        expect(map['heading'], equals(270.0));
      });

      test('handles null optional fields in toMap()', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.interest,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final map = waypoint.toMap();

        expect(map['name'], isNull);
        expect(map['notes'], isNull);
        expect(map['altitude'], isNull);
        expect(map['accuracy'], isNull);
        expect(map['speed'], isNull);
        expect(map['heading'], isNull);
      });
    });

    group('Computed properties', () {
      test('displayName returns name when available', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Golden Chest',
        );

        expect(waypoint.displayName, equals('Golden Chest'));
      });

      test('displayName returns type displayName when name is null', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(waypoint.displayName, equals('Treasure'));
      });

      test('hasGoodAccuracy returns correct values', () {
        final goodAccuracyWaypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          accuracy: 5.0,
        );

        final poorAccuracyWaypoint =
            goodAccuracyWaypoint.copyWith(accuracy: 15.0);
        final nullAccuracyWaypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          // No accuracy set - should be null
        );

        expect(goodAccuracyWaypoint.hasGoodAccuracy, isTrue);
        expect(poorAccuracyWaypoint.hasGoodAccuracy, isFalse);
        expect(nullAccuracyWaypoint.hasGoodAccuracy, isFalse);
      });

      test('accuracyDescription returns correct descriptions', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(waypoint.copyWith().accuracyDescription, equals('Unknown'));
        expect(waypoint.copyWith(accuracy: 2.0).accuracyDescription,
            equals('Excellent'));
        expect(waypoint.copyWith(accuracy: 4.0).accuracyDescription,
            equals('Good'));
        expect(waypoint.copyWith(accuracy: 8.0).accuracyDescription,
            equals('Fair'));
        expect(waypoint.copyWith(accuracy: 15.0).accuracyDescription,
            equals('Poor'));
        expect(waypoint.copyWith(accuracy: 25.0).accuracyDescription,
            equals('Very Poor'));
      });
    });

    group('Distance calculations', () {
      test('distanceTo calculates distance between waypoints', () {
        final waypoint1 = Waypoint(
          id: 'test-1',
          coordinates: const LatLng(40.7128, -74.0060), // NYC
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final waypoint2 = Waypoint(
          id: 'test-2',
          coordinates: const LatLng(40.7589, -73.9851), // Times Square
          type: WaypointType.interest,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final distance = waypoint1.distanceTo(waypoint2);
        expect(distance, greaterThan(0));
        expect(distance, lessThan(10000)); // Should be less than 10km
      });

      test('distanceToCoordinates calculates distance to coordinates', () {
        final waypoint = Waypoint(
          id: 'test-1',
          coordinates: const LatLng(40.7128, -74.0060), // NYC
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        const targetCoordinates = LatLng(40.7589, -73.9851); // Times Square
        final distance = waypoint.distanceToCoordinates(targetCoordinates);
        expect(distance, greaterThan(0));
        expect(distance, lessThan(10000)); // Should be less than 10km
      });

      test('distance calculations are consistent', () {
        final waypoint1 = Waypoint(
          id: 'test-1',
          coordinates: const LatLng(40.7128, -74.0060),
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final waypoint2 = Waypoint(
          id: 'test-2',
          coordinates: const LatLng(40.7589, -73.9851),
          type: WaypointType.interest,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final distance1 = waypoint1.distanceTo(waypoint2);
        final distance2 = waypoint2.distanceTo(waypoint1);
        final distance3 =
            waypoint1.distanceToCoordinates(waypoint2.coordinates);

        expect(distance1, closeTo(distance2, 0.1));
        expect(distance1, closeTo(distance3, 0.1));
      });
    });

    group('Equality and hashCode', () {
      test('equality is based on id', () {
        final waypoint1 = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Waypoint 1',
        );

        final waypoint2 = Waypoint(
          id: 'test-123',
          coordinates: const LatLng(50.0, 50.0), // Different coordinates
          type: WaypointType.warning, // Different type
          timestamp:
              testDateTime.add(const Duration(hours: 1)), // Different time
          sessionId: 'session-789', // Different session
          name: 'Waypoint 2', // Different name
        );

        final waypoint3 = Waypoint(
          id: 'test-456',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Waypoint 1',
        );

        expect(waypoint1, equals(waypoint2)); // Same ID
        expect(waypoint1, isNot(equals(waypoint3))); // Different ID
      });

      test('hashCode is based on id', () {
        final waypoint1 = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final waypoint2 = Waypoint(
          id: 'test-123',
          coordinates: const LatLng(50.0, 50.0),
          type: WaypointType.warning,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        expect(waypoint1.hashCode, equals(waypoint2.hashCode));
      });
    });

    group('toString()', () {
      test('returns formatted string representation', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Golden Chest',
        );

        final result = waypoint.toString();
        expect(result, contains('test-123'));
        expect(result, contains('Treasure'));
        expect(result, contains('40.7128'));
        expect(result, contains('-74.006'));
        expect(result, contains('Golden Chest'));
      });

      test('uses type displayName when name is null', () {
        final waypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.warning,
          timestamp: testDateTime,
          sessionId: 'session-456',
        );

        final result = waypoint.toString();
        expect(result, contains('Warning'));
      });
    });

    group('copyWith()', () {
      late Waypoint originalWaypoint;

      setUp(() {
        originalWaypoint = Waypoint(
          id: 'test-123',
          coordinates: testCoordinates,
          type: WaypointType.treasure,
          timestamp: testDateTime,
          sessionId: 'session-456',
          name: 'Original Waypoint',
          notes: 'Original notes',
          altitude: 100.0,
          accuracy: 5.0,
          speed: 2.0,
          heading: 180.0,
        );
      });

      test('returns identical waypoint when no parameters provided', () {
        final copied = originalWaypoint.copyWith();

        expect(copied.id, equals(originalWaypoint.id));
        expect(copied.coordinates, equals(originalWaypoint.coordinates));
        expect(copied.type, equals(originalWaypoint.type));
        expect(copied.timestamp, equals(originalWaypoint.timestamp));
        expect(copied.sessionId, equals(originalWaypoint.sessionId));
        expect(copied.name, equals(originalWaypoint.name));
        expect(copied.notes, equals(originalWaypoint.notes));
        expect(copied.altitude, equals(originalWaypoint.altitude));
        expect(copied.accuracy, equals(originalWaypoint.accuracy));
        expect(copied.speed, equals(originalWaypoint.speed));
        expect(copied.heading, equals(originalWaypoint.heading));
      });

      test('updates only specified parameters', () {
        const newCoordinates = LatLng(50.0, 50.0);
        final newDateTime = testDateTime.add(const Duration(hours: 1));

        final copied = originalWaypoint.copyWith(
          coordinates: newCoordinates,
          type: WaypointType.warning,
          timestamp: newDateTime,
          name: 'Updated Waypoint',
        );

        expect(copied.coordinates, equals(newCoordinates));
        expect(copied.type, equals(WaypointType.warning));
        expect(copied.timestamp, equals(newDateTime));
        expect(copied.name, equals('Updated Waypoint'));
        // Unchanged values
        expect(copied.id, equals(originalWaypoint.id));
        expect(copied.sessionId, equals(originalWaypoint.sessionId));
        expect(copied.notes, equals(originalWaypoint.notes));
        expect(copied.altitude, equals(originalWaypoint.altitude));
        expect(copied.accuracy, equals(originalWaypoint.accuracy));
        expect(copied.speed, equals(originalWaypoint.speed));
        expect(copied.heading, equals(originalWaypoint.heading));
      });

      test('can update all parameters', () {
        const newCoordinates = LatLng(50.0, 50.0);
        final newDateTime = testDateTime.add(const Duration(hours: 1));

        final copied = originalWaypoint.copyWith(
          id: 'new-id',
          coordinates: newCoordinates,
          type: WaypointType.camp,
          timestamp: newDateTime,
          sessionId: 'new-session',
          name: 'New Waypoint',
          notes: 'New notes',
          altitude: 200.0,
          accuracy: 3.0,
          speed: 5.0,
          heading: 90.0,
        );

        expect(copied.id, equals('new-id'));
        expect(copied.coordinates, equals(newCoordinates));
        expect(copied.type, equals(WaypointType.camp));
        expect(copied.timestamp, equals(newDateTime));
        expect(copied.sessionId, equals('new-session'));
        expect(copied.name, equals('New Waypoint'));
        expect(copied.notes, equals('New notes'));
        expect(copied.altitude, equals(200.0));
        expect(copied.accuracy, equals(3.0));
        expect(copied.speed, equals(5.0));
        expect(copied.heading, equals(90.0));
      });
    });
  });
}
