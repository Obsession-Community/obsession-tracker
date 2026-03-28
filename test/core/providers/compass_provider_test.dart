import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/core/providers/compass_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompassProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should provide initial compass state', () {
      final compassState = container.read(compassProvider);

      expect(compassState.heading, equals(0.0));
      expect(compassState.mapRotation, equals(0.0));
      expect(compassState.isActive, isFalse);
      expect(compassState.isCalibrated, isFalse);
      expect(compassState.isUsingGpsFallback, isFalse);
      expect(compassState.accuracyDescription, equals('Inactive'));
      expect(compassState.errorMessage, isNull);
    });

    test('should provide compass heading through convenience provider', () {
      final heading = container.read(compassHeadingProvider);

      expect(heading, equals(0.0));
    });

    test('should provide compass active status through convenience provider',
        () {
      final isActive = container.read(compassActiveProvider);

      expect(isActive, isFalse);
    });

    test(
        'should provide compass calibration status through convenience provider',
        () {
      final isCalibrated = container.read(compassCalibratedProvider);

      expect(isCalibrated, isFalse);
    });

    test('should provide compass direction name through convenience provider',
        () {
      final direction = container.read(compassDirectionProvider);

      expect(direction, equals('N')); // 0 degrees = North
    });

    test('should provide compass bearing text through convenience provider',
        () {
      final bearing = container.read(compassBearingProvider);

      expect(bearing, equals('0° N'));
    });

    test('should provide map rotation through convenience provider', () {
      final mapRotation = container.read(mapRotationProvider);

      expect(mapRotation, equals(0.0));
    });

    test('should provide map rotated status through convenience provider', () {
      final isMapRotated = container.read(mapRotatedProvider);

      expect(isMapRotated, isFalse); // 0 degrees = not rotated
    });

    test('should handle compass state updates', () async {
      final notifier = container.read(compassProvider.notifier);

      // Test direction name calculation
      expect(notifier.getDirectionName(0), equals('N'));
      expect(notifier.getDirectionName(90), equals('E'));
      expect(notifier.getDirectionName(180), equals('S'));
      expect(notifier.getDirectionName(270), equals('W'));
      expect(notifier.getDirectionName(45), equals('NE'));
    });

    test('should handle bearing text calculation', () async {
      final notifier = container.read(compassProvider.notifier);

      expect(notifier.getBearingText(0), equals('0° N'));
      expect(notifier.getBearingText(90), equals('90° E'));
      expect(notifier.getBearingText(180), equals('180° S'));
      expect(notifier.getBearingText(270), equals('270° W'));
      expect(notifier.getBearingText(45), equals('45° NE'));
    });

    test('should handle map rotation updates', () async {
      final notifier = container.read(compassProvider.notifier);

      // Update map rotation
      notifier.updateMapRotation(90.0);

      final state = container.read(compassProvider);
      expect(state.mapRotation, equals(90.0));
      expect(state.isMapRotated, isTrue);
    });

    test('should handle reset map to north', () async {
      final notifier = container.read(compassProvider.notifier);

      // Set initial rotation
      notifier.updateMapRotation(180.0);
      expect(container.read(compassProvider).mapRotation, equals(180.0));

      // Reset to north
      final targetRotation = notifier.resetMapToNorth();

      // Should return 0 for rotation less than 180
      expect(targetRotation, equals(0.0));
      expect(container.read(compassProvider).mapRotation, equals(0.0));
    });

    test('should handle reset map to north with wraparound', () async {
      final notifier = container.read(compassProvider.notifier);

      // Set rotation > 180 degrees
      notifier.updateMapRotation(270.0);
      expect(container.read(compassProvider).mapRotation, equals(270.0));

      // Reset to north
      final targetRotation = notifier.resetMapToNorth();

      // Should return 360 for shortest path when > 180
      expect(targetRotation, equals(360.0));
      expect(container.read(compassProvider).mapRotation, equals(0.0));
    });

    test('should handle compass state equality', () {
      const state1 = CompassState(heading: 45.0, isActive: true);
      const state2 = CompassState(heading: 45.0, isActive: true);
      const state3 = CompassState(heading: 90.0, isActive: true);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should handle compass state copyWith', () {
      const originalState = CompassState(heading: 45.0);
      final updatedState =
          originalState.copyWith(isActive: true, heading: 90.0);

      expect(updatedState.heading, equals(90.0));
      expect(updatedState.isActive, isTrue);
      expect(updatedState.isCalibrated, equals(originalState.isCalibrated));
    });

    test('should handle map rotation normalization', () {
      final notifier = container.read(compassProvider.notifier);

      // Test rotation normalization
      notifier.updateMapRotation(450.0); // 450 degrees = 90 degrees
      expect(container.read(compassProvider).mapRotation, equals(90.0));

      notifier.updateMapRotation(-90.0); // -90 degrees = 270 degrees
      expect(container.read(compassProvider).mapRotation, equals(270.0));
    });

    test('should detect map rotation correctly', () {
      const state1 = CompassState();
      const state2 = CompassState(mapRotation: 3.0); // Within tolerance
      const state3 = CompassState(mapRotation: 10.0); // Outside tolerance
      const state4 = CompassState(mapRotation: 355.0); // Close to 360/0

      expect(state1.isMapRotated, isFalse);
      expect(state2.isMapRotated, isFalse);
      expect(state3.isMapRotated, isTrue);
      expect(state4.isMapRotated, isTrue);
    });
  });
}
