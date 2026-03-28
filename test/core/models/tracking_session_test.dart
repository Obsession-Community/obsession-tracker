import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';

void main() {
  group('TrackingSession', () {
    late DateTime testDateTime;
    late Map<String, dynamic> testMap;

    setUp(() {
      // Set up metric system for consistent test results
      InternationalizationService().setMeasurementSystemForTesting('metric');
      testDateTime = DateTime(2024, 1, 15, 10, 30);
      testMap = {
        'id': 'test-session-123',
        'name': 'Test Adventure',
        'description': 'A test tracking session',
        'status': 'active',
        'created_at': testDateTime.millisecondsSinceEpoch,
        'started_at':
            testDateTime.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        'completed_at': null,
        'total_distance': 1500.0,
        'total_duration': 3600000, // 1 hour in milliseconds
        'breadcrumb_count': 120,
        'accuracy_threshold': 10.0,
        'recording_interval': 5,
        'start_latitude': 40.7128,
        'start_longitude': -74.0060,
        'end_latitude': null,
        'end_longitude': null,
        'minimum_speed': 0.5,
        'record_altitude': 1,
        'record_speed': 1,
        'record_heading': 1,
      };
    });

    group('Constructor', () {
      test('creates instance with required parameters', () {
        final session = TrackingSession(
          id: 'test-123',
          name: 'Test Session',
          status: SessionStatus.active,
          createdAt: testDateTime,
        );

        expect(session.id, equals('test-123'));
        expect(session.name, equals('Test Session'));
        expect(session.status, equals(SessionStatus.active));
        expect(session.createdAt, equals(testDateTime));
        expect(session.totalDistance, equals(0.0));
        expect(session.totalDuration, equals(0));
        expect(session.breadcrumbCount, equals(0));
        expect(session.accuracyThreshold, equals(10.0));
        expect(session.recordingInterval, equals(5));
        expect(session.minimumSpeed, equals(0.0));
        expect(session.recordAltitude, isTrue);
        expect(session.recordSpeed, isTrue);
        expect(session.recordHeading, isTrue);
      });

      test('creates instance with all parameters', () {
        const startLocation = LatLng(40.7128, -74.0060);
        const endLocation = LatLng(40.7589, -73.9851);

        final session = TrackingSession(
          id: 'test-123',
          name: 'Test Session',
          description: 'Test description',
          status: SessionStatus.completed,
          createdAt: testDateTime,
          startedAt: testDateTime.add(const Duration(minutes: 5)),
          completedAt: testDateTime.add(const Duration(hours: 1)),
          totalDistance: 1500.0,
          totalDuration: 3600000,
          breadcrumbCount: 120,
          accuracyThreshold: 15.0,
          recordingInterval: 10,
          startLocation: startLocation,
          endLocation: endLocation,
          minimumSpeed: 1.0,
          recordAltitude: false,
          recordSpeed: false,
          recordHeading: false,
        );

        expect(session.description, equals('Test description'));
        expect(session.status, equals(SessionStatus.completed));
        expect(session.startedAt,
            equals(testDateTime.add(const Duration(minutes: 5))));
        expect(session.completedAt,
            equals(testDateTime.add(const Duration(hours: 1))));
        expect(session.totalDistance, equals(1500.0));
        expect(session.totalDuration, equals(3600000));
        expect(session.breadcrumbCount, equals(120));
        expect(session.accuracyThreshold, equals(15.0));
        expect(session.recordingInterval, equals(10));
        expect(session.startLocation, equals(startLocation));
        expect(session.endLocation, equals(endLocation));
        expect(session.minimumSpeed, equals(1.0));
        expect(session.recordAltitude, isFalse);
        expect(session.recordSpeed, isFalse);
        expect(session.recordHeading, isFalse);
      });
    });

    group('Factory constructors', () {
      test('create() creates session with default settings', () {
        final session = TrackingSession.create(
          id: 'test-123',
          name: 'Test Session',
        );

        expect(session.id, equals('test-123'));
        expect(session.name, equals('Test Session'));
        expect(session.status, equals(SessionStatus.active));
        expect(session.accuracyThreshold, equals(10.0));
        expect(session.recordingInterval, equals(5));
        expect(session.minimumSpeed, equals(0.0));
        expect(session.recordAltitude, isTrue);
        expect(session.recordSpeed, isTrue);
        expect(session.recordHeading, isTrue);
      });

      test('create() creates session with custom settings', () {
        final session = TrackingSession.create(
          id: 'test-123',
          name: 'Test Session',
          description: 'Custom session',
          accuracyThreshold: 15.0,
          recordingInterval: 10,
          minimumSpeed: 1.0,
          recordAltitude: false,
          recordSpeed: false,
          recordHeading: false,
        );

        expect(session.description, equals('Custom session'));
        expect(session.accuracyThreshold, equals(15.0));
        expect(session.recordingInterval, equals(10));
        expect(session.minimumSpeed, equals(1.0));
        expect(session.recordAltitude, isFalse);
        expect(session.recordSpeed, isFalse);
        expect(session.recordHeading, isFalse);
      });

      test('fromMap() creates session from database map', () {
        final session = TrackingSession.fromMap(testMap);

        expect(session.id, equals('test-session-123'));
        expect(session.name, equals('Test Adventure'));
        expect(session.description, equals('A test tracking session'));
        expect(session.status, equals(SessionStatus.active));
        expect(session.createdAt, equals(testDateTime));
        expect(session.startedAt,
            equals(testDateTime.add(const Duration(minutes: 5))));
        expect(session.completedAt, isNull);
        expect(session.totalDistance, equals(1500.0));
        expect(session.totalDuration, equals(3600000));
        expect(session.breadcrumbCount, equals(120));
        expect(session.accuracyThreshold, equals(10.0));
        expect(session.recordingInterval, equals(5));
        expect(session.startLocation?.latitude, equals(40.7128));
        expect(session.startLocation?.longitude, equals(-74.0060));
        expect(session.endLocation, isNull);
        expect(session.minimumSpeed, equals(0.5));
        expect(session.recordAltitude, isTrue);
        expect(session.recordSpeed, isTrue);
        expect(session.recordHeading, isTrue);
      });

      test('fromMap() handles invalid status gracefully', () {
        final mapWithInvalidStatus = Map<String, dynamic>.from(testMap);
        mapWithInvalidStatus['status'] = 'invalid_status';

        final session = TrackingSession.fromMap(mapWithInvalidStatus);
        expect(session.status, equals(SessionStatus.cancelled));
      });

      test('fromMap() handles null optional fields', () {
        final mapWithNulls = {
          'id': 'test-123',
          'name': 'Test',
          'description': null,
          'status': 'active',
          'created_at': testDateTime.millisecondsSinceEpoch,
          'started_at': null,
          'completed_at': null,
          'total_distance': 0.0,
          'total_duration': 0,
          'breadcrumb_count': 0,
          'accuracy_threshold': 10.0,
          'recording_interval': 5,
          'start_latitude': null,
          'start_longitude': null,
          'end_latitude': null,
          'end_longitude': null,
          'minimum_speed': 0.0,
          'record_altitude': 0,
          'record_speed': 0,
          'record_heading': 0,
        };

        final session = TrackingSession.fromMap(mapWithNulls);
        expect(session.description, isNull);
        expect(session.startedAt, isNull);
        expect(session.completedAt, isNull);
        expect(session.startLocation, isNull);
        expect(session.endLocation, isNull);
        expect(session.recordAltitude, isFalse);
        expect(session.recordSpeed, isFalse);
        expect(session.recordHeading, isFalse);
      });
    });

    group('toMap()', () {
      test('converts session to map correctly', () {
        const startLocation = LatLng(40.7128, -74.0060);
        const endLocation = LatLng(40.7589, -73.9851);
        final session = TrackingSession(
          id: 'test-123',
          name: 'Test Session',
          description: 'Test description',
          status: SessionStatus.completed,
          createdAt: testDateTime,
          startedAt: testDateTime.add(const Duration(minutes: 5)),
          completedAt: testDateTime.add(const Duration(hours: 1)),
          totalDistance: 1500.0,
          totalDuration: 3600000,
          breadcrumbCount: 120,
          accuracyThreshold: 15.0,
          recordingInterval: 10,
          startLocation: startLocation,
          endLocation: endLocation,
          minimumSpeed: 1.0,
          recordAltitude: false,
          recordHeading: false,
        );

        final map = session.toMap();

        expect(map['id'], equals('test-123'));
        expect(map['name'], equals('Test Session'));
        expect(map['description'], equals('Test description'));
        expect(map['status'], equals('completed'));
        expect(map['created_at'], equals(testDateTime.millisecondsSinceEpoch));
        expect(
            map['started_at'],
            equals(testDateTime
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch));
        expect(
            map['completed_at'],
            equals(testDateTime
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch));
        expect(map['total_distance'], equals(1500.0));
        expect(map['total_duration'], equals(3600000));
        expect(map['breadcrumb_count'], equals(120));
        expect(map['accuracy_threshold'], equals(15.0));
        expect(map['recording_interval'], equals(10));
        expect(map['start_latitude'], equals(40.7128));
        expect(map['start_longitude'], equals(-74.0060));
        expect(map['end_latitude'], equals(40.7589));
        expect(map['end_longitude'], equals(-73.9851));
        expect(map['minimum_speed'], equals(1.0));
        expect(map['record_altitude'], equals(0));
        expect(map['record_speed'], equals(1));
        expect(map['record_heading'], equals(0));
      });

      test('handles null optional fields in toMap()', () {
        final session = TrackingSession(
          id: 'test-123',
          name: 'Test Session',
          status: SessionStatus.active,
          createdAt: testDateTime,
        );

        final map = session.toMap();

        expect(map['description'], isNull);
        expect(map['started_at'], isNull);
        expect(map['completed_at'], isNull);
        expect(map['start_latitude'], isNull);
        expect(map['start_longitude'], isNull);
        expect(map['end_latitude'], isNull);
        expect(map['end_longitude'], isNull);
      });
    });

    group('Status getters', () {
      test('isActive returns correct value', () {
        final activeSession = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
        );
        final pausedSession =
            activeSession.copyWith(status: SessionStatus.paused);

        expect(activeSession.isActive, isTrue);
        expect(pausedSession.isActive, isFalse);
      });

      test('isPaused returns correct value', () {
        final pausedSession = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.paused,
          createdAt: testDateTime,
        );
        final activeSession =
            pausedSession.copyWith(status: SessionStatus.active);

        expect(pausedSession.isPaused, isTrue);
        expect(activeSession.isPaused, isFalse);
      });

      test('isCompleted returns correct value', () {
        final completedSession = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.completed,
          createdAt: testDateTime,
        );
        final activeSession =
            completedSession.copyWith(status: SessionStatus.active);

        expect(completedSession.isCompleted, isTrue);
        expect(activeSession.isCompleted, isFalse);
      });
    });

    group('Calculated properties', () {
      test('duration returns correct Duration object', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDuration: 3600000, // 1 hour
        );

        expect(session.duration, equals(const Duration(hours: 1)));
      });

      test('averageSpeed calculates correctly', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDistance: 1000.0, // 1000 meters
          totalDuration: 500000, // 500 seconds
        );

        expect(session.averageSpeed, equals(2.0)); // 1000m / 500s = 2 m/s
      });

      test('averageSpeed returns null for zero distance', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDuration: 3600000,
        );

        expect(session.averageSpeed, isNull);
      });

      test('averageSpeed returns null for zero duration', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDistance: 1000.0,
        );

        expect(session.averageSpeed, isNull);
      });

      test('formattedDuration formats correctly with hours', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDuration: 3665000, // 1 hour, 1 minute, 5 seconds
        );

        expect(session.formattedDuration, equals('01:01:05'));
      });

      test('formattedDuration formats correctly without hours', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDuration: 125000, // 2 minutes, 5 seconds
        );

        expect(session.formattedDuration, equals('02:05'));
      });

      test('formattedDistance formats meters correctly', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDistance: 50.0, // Under 100m threshold shows in meters
        );

        expect(session.formattedDistance, equals('50 m'));
      });

      test('formattedDistance formats kilometers correctly', () {
        final session = TrackingSession(
          id: 'test',
          name: 'Test',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDistance: 2500.0,
        );

        expect(session.formattedDistance, equals('2.50 km'));
      });
    });

    group('Equality and hashCode', () {
      test('equality is based on id', () {
        final session1 = TrackingSession(
          id: 'test-123',
          name: 'Session 1',
          status: SessionStatus.active,
          createdAt: testDateTime,
        );
        final session2 = TrackingSession(
          id: 'test-123',
          name: 'Session 2', // Different name
          status: SessionStatus.completed, // Different status
          createdAt:
              testDateTime.add(const Duration(hours: 1)), // Different time
        );
        final session3 = TrackingSession(
          id: 'test-456',
          name: 'Session 1',
          status: SessionStatus.active,
          createdAt: testDateTime,
        );

        expect(session1, equals(session2)); // Same ID
        expect(session1, isNot(equals(session3))); // Different ID
      });

      test('hashCode is based on id', () {
        final session1 = TrackingSession(
          id: 'test-123',
          name: 'Session 1',
          status: SessionStatus.active,
          createdAt: testDateTime,
        );
        final session2 = TrackingSession(
          id: 'test-123',
          name: 'Session 2',
          status: SessionStatus.completed,
          createdAt: testDateTime,
        );

        expect(session1.hashCode, equals(session2.hashCode));
      });
    });

    group('toString()', () {
      test('returns formatted string representation', () {
        final session = TrackingSession(
          id: 'test-123',
          name: 'Test Session',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDistance: 1500.0,
          totalDuration: 3600000,
        );

        final result = session.toString();
        expect(result, contains('test-123'));
        expect(result, contains('Test Session'));
        expect(result, contains('active'));
        expect(result, contains('1.50 km'));
        expect(result, contains('01:00:00'));
      });
    });

    group('copyWith()', () {
      late TrackingSession originalSession;

      setUp(() {
        originalSession = TrackingSession(
          id: 'test-123',
          name: 'Original Session',
          description: 'Original description',
          status: SessionStatus.active,
          createdAt: testDateTime,
          totalDistance: 1000.0,
          totalDuration: 1800000,
          breadcrumbCount: 60,
        );
      });

      test('returns identical session when no parameters provided', () {
        final copied = originalSession.copyWith();

        expect(copied.id, equals(originalSession.id));
        expect(copied.name, equals(originalSession.name));
        expect(copied.description, equals(originalSession.description));
        expect(copied.status, equals(originalSession.status));
        expect(copied.createdAt, equals(originalSession.createdAt));
        expect(copied.totalDistance, equals(originalSession.totalDistance));
        expect(copied.totalDuration, equals(originalSession.totalDuration));
        expect(copied.breadcrumbCount, equals(originalSession.breadcrumbCount));
      });

      test('updates only specified parameters', () {
        final copied = originalSession.copyWith(
          name: 'Updated Session',
          status: SessionStatus.completed,
          totalDistance: 2000.0,
        );

        expect(copied.name, equals('Updated Session'));
        expect(copied.status, equals(SessionStatus.completed));
        expect(copied.totalDistance, equals(2000.0));
        // Unchanged values
        expect(copied.id, equals(originalSession.id));
        expect(copied.description, equals(originalSession.description));
        expect(copied.createdAt, equals(originalSession.createdAt));
        expect(copied.totalDuration, equals(originalSession.totalDuration));
        expect(copied.breadcrumbCount, equals(originalSession.breadcrumbCount));
      });

      test('can update all parameters', () {
        final newDateTime = testDateTime.add(const Duration(hours: 2));
        const startLocation = LatLng(40.7128, -74.0060);
        const endLocation = LatLng(40.7589, -73.9851);

        final copied = originalSession.copyWith(
          id: 'new-id',
          name: 'New Session',
          description: 'New description',
          status: SessionStatus.completed,
          createdAt: newDateTime,
          startedAt: newDateTime.add(const Duration(minutes: 5)),
          completedAt: newDateTime.add(const Duration(hours: 1)),
          totalDistance: 3000.0,
          totalDuration: 7200000,
          breadcrumbCount: 240,
          accuracyThreshold: 15.0,
          recordingInterval: 10,
          startLocation: startLocation,
          endLocation: endLocation,
          minimumSpeed: 1.0,
          recordAltitude: false,
          recordSpeed: false,
          recordHeading: false,
        );

        expect(copied.id, equals('new-id'));
        expect(copied.name, equals('New Session'));
        expect(copied.description, equals('New description'));
        expect(copied.status, equals(SessionStatus.completed));
        expect(copied.createdAt, equals(newDateTime));
        expect(copied.startedAt,
            equals(newDateTime.add(const Duration(minutes: 5))));
        expect(copied.completedAt,
            equals(newDateTime.add(const Duration(hours: 1))));
        expect(copied.totalDistance, equals(3000.0));
        expect(copied.totalDuration, equals(7200000));
        expect(copied.breadcrumbCount, equals(240));
        expect(copied.accuracyThreshold, equals(15.0));
        expect(copied.recordingInterval, equals(10));
        expect(copied.startLocation, equals(startLocation));
        expect(copied.endLocation, equals(endLocation));
        expect(copied.minimumSpeed, equals(1.0));
        expect(copied.recordAltitude, isFalse);
        expect(copied.recordSpeed, isFalse);
        expect(copied.recordHeading, isFalse);
      });
    });
  });

  group('SessionStatus', () {
    test('has correct enum values', () {
      expect(SessionStatus.values.length, equals(4));
      expect(SessionStatus.values, contains(SessionStatus.active));
      expect(SessionStatus.values, contains(SessionStatus.paused));
      expect(SessionStatus.values, contains(SessionStatus.completed));
      expect(SessionStatus.values, contains(SessionStatus.cancelled));
    });

    test('enum names are correct', () {
      expect(SessionStatus.active.name, equals('active'));
      expect(SessionStatus.paused.name, equals('paused'));
      expect(SessionStatus.completed.name, equals('completed'));
      expect(SessionStatus.cancelled.name, equals('cancelled'));
    });
  });
}
