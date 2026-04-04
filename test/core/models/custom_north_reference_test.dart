import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/core/models/custom_north_reference.dart';

void main() {
  group('CustomNorthReference', () {
    test('create() generates UUID and timestamp', () {
      final ref = CustomNorthReference.create(
        name: 'Polaris Peak',
        latitude: 45.3772,
        longitude: -113.7872,
      );

      expect(ref.id, isNotEmpty);
      expect(ref.id.length, equals(36)); // UUID v4 format
      expect(ref.name, equals('Polaris Peak'));
      expect(ref.latitude, equals(45.3772));
      expect(ref.longitude, equals(-113.7872));
      expect(ref.createdAt, isNotNull);
      expect(ref.updatedAt, isNull);
    });

    test('toMap() serializes correctly', () {
      final created = DateTime(2026, 4, 3, 12);
      final ref = CustomNorthReference(
        id: 'test-id-123',
        name: 'Test Peak',
        latitude: 40.0,
        longitude: -110.0,
        createdAt: created,
      );

      final map = ref.toMap();

      expect(map['id'], equals('test-id-123'));
      expect(map['name'], equals('Test Peak'));
      expect(map['latitude'], equals(40.0));
      expect(map['longitude'], equals(-110.0));
      expect(map['created_at'], equals(created.millisecondsSinceEpoch));
      expect(map['updated_at'], isNull);
    });

    test('fromMap() deserializes correctly', () {
      final createdMs = DateTime(2026, 4, 3).millisecondsSinceEpoch;
      final updatedMs = DateTime(2026, 4, 4).millisecondsSinceEpoch;

      final ref = CustomNorthReference.fromMap({
        'id': 'abc-123',
        'name': 'Mountain Top',
        'latitude': 46.5,
        'longitude': -112.0,
        'created_at': createdMs,
        'updated_at': updatedMs,
      });

      expect(ref.id, equals('abc-123'));
      expect(ref.name, equals('Mountain Top'));
      expect(ref.latitude, equals(46.5));
      expect(ref.longitude, equals(-112.0));
      expect(ref.createdAt.millisecondsSinceEpoch, equals(createdMs));
      expect(ref.updatedAt?.millisecondsSinceEpoch, equals(updatedMs));
    });

    test('fromMap() handles null updated_at', () {
      final ref = CustomNorthReference.fromMap({
        'id': 'abc-123',
        'name': 'Peak',
        'latitude': 40.0,
        'longitude': -110.0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': null,
      });

      expect(ref.updatedAt, isNull);
    });

    test('toMap/fromMap round-trip preserves data', () {
      final original = CustomNorthReference.create(
        name: 'Round Trip Peak',
        latitude: 44.4272,
        longitude: -110.5885,
      );

      final map = original.toMap();
      final restored = CustomNorthReference.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.latitude, equals(original.latitude));
      expect(restored.longitude, equals(original.longitude));
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        equals(original.createdAt.millisecondsSinceEpoch),
      );
    });

    test('copyWith() changes specified fields', () {
      final original = CustomNorthReference.create(
        name: 'Original',
        latitude: 40.0,
        longitude: -110.0,
      );
      final updated = DateTime(2026, 5);

      final modified = original.copyWith(
        name: 'Modified',
        latitude: 45.0,
        updatedAt: updated,
      );

      expect(modified.id, equals(original.id)); // Preserved
      expect(modified.name, equals('Modified')); // Changed
      expect(modified.latitude, equals(45.0)); // Changed
      expect(modified.longitude, equals(-110.0)); // Preserved
      expect(modified.updatedAt, equals(updated)); // Changed
    });

    test('copyWith() preserves unchanged fields', () {
      final original = CustomNorthReference.create(
        name: 'Keep Me',
        latitude: 42.0,
        longitude: -111.0,
      );

      final copy = original.copyWith();

      expect(copy.id, equals(original.id));
      expect(copy.name, equals(original.name));
      expect(copy.latitude, equals(original.latitude));
      expect(copy.longitude, equals(original.longitude));
      expect(copy.createdAt, equals(original.createdAt));
    });

    test('equality works correctly', () {
      final created = DateTime(2026, 4, 3);
      final a = CustomNorthReference(
        id: 'same-id',
        name: 'Peak',
        latitude: 40.0,
        longitude: -110.0,
        createdAt: created,
      );
      final b = CustomNorthReference(
        id: 'same-id',
        name: 'Peak',
        latitude: 40.0,
        longitude: -110.0,
        createdAt: created,
      );
      final c = CustomNorthReference(
        id: 'different-id',
        name: 'Peak',
        latitude: 40.0,
        longitude: -110.0,
        createdAt: created,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString() includes key fields', () {
      final ref = CustomNorthReference.create(
        name: 'Debug Peak',
        latitude: 45.0,
        longitude: -113.0,
      );

      final str = ref.toString();
      expect(str, contains('Debug Peak'));
      expect(str, contains('45.0'));
      expect(str, contains('-113.0'));
    });
  });
}
